using AgroAPI.Application.DTOs;
using AgroAPI.Application.ViewModels;

namespace AgroAPI.Application.Interfaces;

public interface ICultivoService
{
    Task<CultivoDto?> GetCultivoByIdAsync(int id);
    Task<IEnumerable<CultivoDto>> GetAllCultivosAsync(bool includeDeleted);
    Task<CultivoDto> CreateCultivoAsync(CultivoCreateViewModel cultivoViewModel);
    Task<bool> UpdateCultivoAsync(int id, CultivoUpdateViewModel cultivoViewModel);
    Task<bool> DeleteCultivoAsync(int id);
    Task<bool> RestoreCultivoAsync(int id);
}