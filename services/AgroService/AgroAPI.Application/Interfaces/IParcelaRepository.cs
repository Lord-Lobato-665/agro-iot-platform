using AgroAPI.Application.DTOs;
using AgroAPI.Domain.Entities;

namespace AgroAPI.Application.Interfaces;

public interface IParcelaRepository
{
    Task<ParcelaDto?> GetByIdAsync(Guid id);
    Task<IEnumerable<ParcelaDto>> GetAllAsync(bool includeDeleted);
    Task<Parcela> CreateAsync(Parcela parcela, List<int> cultivosIds);
    Task<bool> UpdateAsync(Guid id, Parcela parcela, List<int> cultivosIds);
    Task<bool> DeleteAsync(Guid id);
    Task<bool> ExistsAsync(Guid id); // Método de utilidad para validaciones
    Task<bool> RestoreAsync(Guid id); 
}