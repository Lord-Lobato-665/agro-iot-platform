using AgroAPI.Application.DTOs;
using AgroAPI.Domain.Entities;

namespace AgroAPI.Application.Interfaces;

public interface ICultivoRepository
{
    Task<CultivoDto?> GetByIdAsync(int id);
    Task<IEnumerable<CultivoDto>> GetAllAsync(bool includeDeleted);
    Task<Cultivo> CreateAsync(Cultivo cultivo);
    Task<bool> UpdateAsync(int id, Cultivo cultivo);
    Task<bool> DeleteAsync(int id);
    Task<bool> ExistsAsync(int id);
    Task<bool> RestoreAsync(int id);
}