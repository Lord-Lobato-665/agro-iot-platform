using AgroAPI.Application.DTOs;
using AgroAPI.Application.ViewModels;

namespace AgroAPI.Application.Interfaces;

public interface IParcelaService
{
    Task<ParcelaDto?> GetParcelaByIdAsync(Guid id);
    Task<IEnumerable<ParcelaDto>> GetAllParcelasAsync(bool includeDeleted);
    Task<ParcelaDto> CreateParcelaAsync(ParcelaCreateViewModel parcelaViewModel);
    Task<bool> UpdateParcelaAsync(Guid id, ParcelaUpdateViewModel parcelaViewModel);
    Task<bool> DeleteParcelaAsync(Guid id);
    Task<bool> RestoreParcelaAsync(Guid id);
}