namespace AgroAPI.Domain.Entities;

public class Usuario
{
    public int Id { get; set; }
    public string Nombre { get; set; }
    public string Correo { get; set; }
    public string PasswordHash { get; set; } // NUNCA guardar contraseñas en texto plano
    public string Telefono { get; set; }
    public bool IsDeleted { get; set; }
    
    // Propiedad de navegación
    public ICollection<ParcelaUsuario> ParcelaUsuarios { get; set; } = new List<ParcelaUsuario>();
    public ICollection<UsuarioRol> UsuarioRoles { get; set; } = new List<UsuarioRol>();
}
