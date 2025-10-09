using AgroAPI.Application.Interfaces;
using AgroAPI.Domain.Entities;
using AgroAPI.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using System.Threading.Tasks;
using AgroAPI.Application.DTOs;
using System.Linq;
using System.Collections.Generic;

namespace AgroAPI.Infrastructure.Repositories;

public class RolRepository : IRolRepository
{
    private readonly ApplicationDbContext _context;

    public RolRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<Rol?> GetRolByNameAsync(string name)
    {
        return await _context.Roles.FirstOrDefaultAsync(r => r.Nombre == name);
    }

    public async Task<IEnumerable<RolDto>> GetAllRolesAsync()
    {
        return await _context.Roles
            .Select(r => new RolDto
            {
                Id = r.Id,
                Nombre = r.Nombre
            })
            .ToListAsync();
    }
}