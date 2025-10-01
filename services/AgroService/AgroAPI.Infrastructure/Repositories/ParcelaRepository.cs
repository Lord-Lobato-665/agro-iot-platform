using AgroAPI.Application.DTOs;
using AgroAPI.Application.Interfaces;
using AgroAPI.Domain.Entities;
using AgroAPI.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace AgroAPI.Infrastructure.Repositories;

public class ParcelaRepository : IParcelaRepository
{
    private readonly ApplicationDbContext _context;

    public ParcelaRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<ParcelaDto>> GetAllAsync(bool includeDeleted)
    {
        // Empezamos con la consulta base
        var query = _context.Parcelas.AsQueryable();

        // Si el parámetro es true, ignoramos los filtros globales
        if (includeDeleted)
        {
            query = query.IgnoreQueryFilters();
        }

        // El resto de la proyección continúa desde la consulta que hemos construido
        return await query
            .AsNoTracking()
            .Select(p => new ParcelaDto
            {
                Id = p.Id,
                Nombre = p.Nombre,
                Latitud = p.Latitud,
                Longitud = p.Longitud,
                CantidadCultivos = p.CantidadCultivos,
                NombresCultivos = p.ParcelaCultivos.Select(pc => pc.Cultivo.Nombre).ToList(),
                IsDeleted = p.IsDeleted // Mapeamos la nueva propiedad
            })
            .ToListAsync();
    }

    public async Task<ParcelaDto?> GetByIdAsync(Guid id)
    {
        return await _context.Parcelas
            .AsNoTracking()
            .Where(p => p.Id == id)
            .Select(p => new ParcelaDto
            {
                Id = p.Id,
                Nombre = p.Nombre,
                Latitud = p.Latitud,
                Longitud = p.Longitud,
                CantidadCultivos = p.CantidadCultivos,
                NombresCultivos = p.ParcelaCultivos.Select(pc => pc.Cultivo.Nombre).ToList()
            })
            .FirstOrDefaultAsync();
    }

    public async Task<Parcela> CreateAsync(Parcela parcela, List<int> cultivosIds)
    {
        parcela.Id = Guid.NewGuid();

        // Verificamos si se proporcionaron IDs de cultivos
        if (cultivosIds != null && cultivosIds.Any())
        {
            foreach (var cultivoId in cultivosIds)
            {
                // --- INICIO DE LA CORRECCIÓN ---

                // 1. Verificamos si el cultivo con este ID existe en la base de datos.
                //    FindAsync es muy eficiente para buscar por clave primaria.
                var cultivoExistente = await _context.Cultivos.FindAsync(cultivoId);

                // 2. Solo si el cultivo existe, creamos la relación.
                if (cultivoExistente != null)
                {
                    parcela.ParcelaCultivos.Add(new ParcelaCultivo { CultivoId = cultivoId });
                }
                // Si el cultivo no existe, simplemente lo ignoramos y continuamos con el siguiente.
                // Esto previene el error de la base de datos.
                
                // --- FIN DE LA CORRECCIÓN ---
            }
        }

        // Finalmente, calculamos la cantidad basándonos únicamente
        // en las relaciones válidas que acabamos de añadir.
        parcela.CantidadCultivos = parcela.ParcelaCultivos.Count;

        await _context.Parcelas.AddAsync(parcela);
        await _context.SaveChangesAsync();
        
        return parcela;
    }

    public async Task<bool> UpdateAsync(Guid id, Parcela parcelaActualizada, List<int> cultivosIds)
    {
        var entidadExistente = await _context.Parcelas
                                    .Include(p => p.ParcelaCultivos) // ¡Importante incluir las relaciones!
                                    .FirstOrDefaultAsync(p => p.Id == id);

        if (entidadExistente == null)
        {
            return false;
        }

        // 1. Actualizar propiedades simples
        entidadExistente.Nombre = parcelaActualizada.Nombre;
        entidadExistente.Latitud = parcelaActualizada.Latitud;
        entidadExistente.Longitud = parcelaActualizada.Longitud;

        // 2. Actualizar la relación muchos a muchos
        entidadExistente.ParcelaCultivos.Clear(); // Borramos las relaciones existentes
        if (cultivosIds != null && cultivosIds.Any())
        {
            foreach (var cultivoId in cultivosIds)
            {
                entidadExistente.ParcelaCultivos.Add(new ParcelaCultivo { CultivoId = cultivoId });
            }
        }
        
        // 3. Actualizamos el contador
        entidadExistente.CantidadCultivos = entidadExistente.ParcelaCultivos.Count;

        _context.Parcelas.Update(entidadExistente);
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> DeleteAsync(Guid id)
    {
        // Usamos .IgnoreQueryFilters() aquí para poder encontrar una parcela
        // incluso si ya está marcada como borrada (y así evitar un "borrado" duplicado).
        // Aunque en la mayoría de los casos un simple FindAsync es suficiente.
        var parcela = await _context.Parcelas
                                    .IgnoreQueryFilters() 
                                    .FirstOrDefaultAsync(p => p.Id == id);
                                    
        if (parcela == null || parcela.IsDeleted) // Si no existe o ya está borrado
        {
            return false;
        }

        // 1. Marcamos la entidad como borrada
        parcela.IsDeleted = true;

        // 2. Guardamos los cambios (esto ejecuta un UPDATE, no un DELETE)
        await _context.SaveChangesAsync();

        return true;
    }

    public async Task<bool> RestoreAsync(Guid id)
    {
        // 1. Usamos IgnoreQueryFilters() para poder encontrar una parcela
        //    que ya fue marcada como borrada.
        var parcela = await _context.Parcelas
                                    .IgnoreQueryFilters()
                                    .FirstOrDefaultAsync(p => p.Id == id);

        // 2. Verificamos que la parcela exista y que esté realmente borrada.
        //    No podemos restaurar algo que no existe o que ya está activo.
        if (parcela == null || !parcela.IsDeleted)
        {
            return false;
        }

        // 3. Cambiamos el estado y guardamos.
        parcela.IsDeleted = false;
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> ExistsAsync(Guid id)
    {
        return await _context.Parcelas.AnyAsync(p => p.Id == id);
    }
}