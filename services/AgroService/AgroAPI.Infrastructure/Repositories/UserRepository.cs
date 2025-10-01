using AgroAPI.Application.Interfaces;
using AgroAPI.Domain.Entities;
using AgroAPI.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using System.Threading.Tasks;
using AgroAPI.Application.DTOs;
using System.Collections.Generic;
using System.Linq;

namespace AgroAPI.Infrastructure.Repositories;

public class UserRepository : IUserRepository
{
    private readonly ApplicationDbContext _context;

    public UserRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<Usuario?> GetUserByEmailAsync(string email)
    {
        return await _context.Usuarios.FirstOrDefaultAsync(u => u.Correo == email);
    }

    public async Task AddUserAsync(Usuario user)
    {
        await _context.Usuarios.AddAsync(user);
        await _context.SaveChangesAsync();
    }

    public async Task<UserDto?> GetByIdAsync(int id)
    {
        return await _context.Usuarios
            .AsNoTracking()
            .Where(u => u.Id == id)
            .Select(u => new UserDto
            {
                Id = u.Id,
                Nombre = u.Nombre,
                Correo = u.Correo,
                Telefono = u.Telefono,
                IsDeleted = u.IsDeleted
            })
            .FirstOrDefaultAsync();
    }
    
    public async Task<IEnumerable<UserDto>> GetAllAsync(bool includeDeleted)
    {
        var query = _context.Usuarios.AsQueryable();

        if (includeDeleted)
        {
            query = query.IgnoreQueryFilters();
        }

        return await query
            .AsNoTracking()
            .Select(u => new UserDto
            {
                Id = u.Id,
                Nombre = u.Nombre,
                Correo = u.Correo,
                Telefono = u.Telefono,
                IsDeleted = u.IsDeleted
            })
            .ToListAsync();
    }
    
    public async Task<bool> UpdateAsync(int id, Usuario userUpdateData)
    {
        var user = await _context.Usuarios.FindAsync(id);
        if (user == null)
        {
            return false;
        }

        user.Nombre = userUpdateData.Nombre;
        user.Telefono = userUpdateData.Telefono;
        
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var user = await _context.Usuarios.FindAsync(id);
        if (user == null)
        {
            return false;
        }
        user.IsDeleted = true;
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> RestoreAsync(int id)
    {
        var user = await _context.Usuarios.IgnoreQueryFilters().FirstOrDefaultAsync(u => u.Id == id);
        if (user == null || !user.IsDeleted)
        {
            return false;
        }
        user.IsDeleted = false;
        await _context.SaveChangesAsync();
        return true;
    }
}