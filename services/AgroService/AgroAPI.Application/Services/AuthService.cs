using AgroAPI.Application.Interfaces;
using AgroAPI.Application.ViewModels;
using AgroAPI.Domain.Entities;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using System;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using BCrypt.Net;


namespace AgroAPI.Application.Services;

public class AuthService : IAuthService
{
    private readonly IUserRepository _userRepository;
    private readonly IRolRepository _rolRepository;
    private readonly IConfiguration _configuration;

    // Modificamos el constructor
    public AuthService(IUserRepository userRepository, IRolRepository rolRepository, IConfiguration configuration)
    {
        _userRepository = userRepository;
        _rolRepository = rolRepository;
        _configuration = configuration;
    }

    public async Task<bool> RegisterAsync(UserRegisterViewModel model)
    {
        var userExists = await _userRepository.GetUserByEmailAsync(model.Correo);
        if (userExists != null)
        {
            return false;
        }

        var user = new Usuario
        {
            Nombre = model.Nombre,
            Correo = model.Correo,
            Telefono = model.Telefono,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(model.Password)
        };

        // Usamos el nuevo repositorio para buscar el rol
        var userRole = await _rolRepository.GetRolByNameAsync("User");
        if (userRole != null)
        {
            user.UsuarioRoles.Add(new UsuarioRol { RolId = userRole.Id });
        }

        await _userRepository.AddUserAsync(user);
        return true;
    }

    public async Task<string?> LoginAsync(UserLoginViewModel model)
    {
        var user = await _userRepository.GetUserByEmailAsync(model.Correo);

        if (user == null || !BCrypt.Net.BCrypt.Verify(model.Password, user.PasswordHash))
        {
            return null;
        }

        return GenerateJwtToken(user);
    }

    private string GenerateJwtToken(Usuario user)
    {
        var tokenHandler = new JwtSecurityTokenHandler();
        var key = Encoding.ASCII.GetBytes(_configuration["Jwt:Key"]);

        // Creamos una lista de claims para poder añadir los roles dinámicamente
        var claims = new List<Claim>
        {
            new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new Claim(JwtRegisteredClaimNames.Email, user.Correo),
            new Claim(JwtRegisteredClaimNames.Name, user.Nombre),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        // --- LÓGICA AÑADIDA PARA LOS ROLES ---
        if (user.UsuarioRoles != null)
        {
            foreach (var usuarioRol in user.UsuarioRoles)
            {
                // Añadimos un claim de tipo "role" por cada rol que tenga el usuario
                claims.Add(new Claim(ClaimTypes.Role, usuarioRol.Rol.Nombre));
            }
        }

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims), 
            Expires = DateTime.UtcNow.AddHours(1),
            Issuer = _configuration["Jwt:Issuer"],
            Audience = _configuration["Jwt:Audience"],
            SigningCredentials = new SigningCredentials(new SymmetricSecurityKey(key), SecurityAlgorithms.HmacSha256Signature)
        };

        var token = tokenHandler.CreateToken(tokenDescriptor);
        return tokenHandler.WriteToken(token);
    }
}