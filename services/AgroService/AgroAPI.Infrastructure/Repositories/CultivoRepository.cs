using AgroAPI.Application.DTOs;
using AgroAPI.Application.Interfaces;
using AgroAPI.Domain.Entities;
using AgroAPI.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace AgroAPI.Infrastructure.Repositories;

public class CultivoRepository : ICultivoRepository
{
    private readonly ApplicationDbContext _context;

    public CultivoRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<CultivoDto?> GetByIdAsync(int id)
    {
        return await _context.Cultivos
            .AsNoTracking()
            .Where(c => c.Id == id)
            .Select(c => new CultivoDto
            {
                Id = c.Id,
                Nombre = c.Nombre,
                IsDeleted = c.IsDeleted
            })
            .FirstOrDefaultAsync();
    }
    
    public async Task<IEnumerable<CultivoDto>> GetAllAsync(bool includeDeleted)
    {
        var query = _context.Cultivos.AsQueryable();

        if (includeDeleted)
        {
            query = query.IgnoreQueryFilters();
        }

        return await query
            .AsNoTracking()
            .Select(c => new CultivoDto
            {
                Id = c.Id,
                Nombre = c.Nombre,
                IsDeleted = c.IsDeleted
            })
            .ToListAsync();
    }
    
    public async Task<Cultivo> CreateAsync(Cultivo cultivo)
    {
        await _context.Cultivos.AddAsync(cultivo);
        await _context.SaveChangesAsync();
        return cultivo;
    }

    public async Task<bool> UpdateAsync(int id, Cultivo cultivoActualizado)
    {
        var entidadExistente = await _context.Cultivos.FindAsync(id);
        if (entidadExistente == null)
        {
            return false;
        }

        entidadExistente.Nombre = cultivoActualizado.Nombre;
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var cultivo = await _context.Cultivos.FindAsync(id);
        if (cultivo == null)
        {
            return false;
        }

        cultivo.IsDeleted = true;
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> RestoreAsync(int id)
    {
        var cultivo = await _context.Cultivos
                                    .IgnoreQueryFilters()
                                    .FirstOrDefaultAsync(c => c.Id == id);

        if (cultivo == null || !cultivo.IsDeleted)
        {
            return false;
        }

        cultivo.IsDeleted = false;
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> ExistsAsync(int id)
    {
        return await _context.Cultivos.AnyAsync(c => c.Id == id);
    }
}