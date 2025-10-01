using AgroAPI.Application.DTOs;
using AgroAPI.Application.Interfaces;
using AgroAPI.Application.ViewModels;
using AgroAPI.Domain.Entities;

namespace AgroAPI.Application.Services;

public class CultivoService : ICultivoService
{
    private readonly ICultivoRepository _cultivoRepository;

    public CultivoService(ICultivoRepository cultivoRepository)
    {
        _cultivoRepository = cultivoRepository;
    }
    
    public Task<CultivoDto?> GetCultivoByIdAsync(int id)
    {
        return _cultivoRepository.GetByIdAsync(id);
    }

    public Task<IEnumerable<CultivoDto>> GetAllCultivosAsync(bool includeDeleted)
    {
        return _cultivoRepository.GetAllAsync(includeDeleted);
    }

    public async Task<CultivoDto> CreateCultivoAsync(CultivoCreateViewModel viewModel)
    {
        var cultivoEntidad = new Cultivo { Nombre = viewModel.Nombre };
        var nuevoCultivo = await _cultivoRepository.CreateAsync(cultivoEntidad);
        
        return new CultivoDto
        {
            Id = nuevoCultivo.Id,
            Nombre = nuevoCultivo.Nombre,
            IsDeleted = nuevoCultivo.IsDeleted
        };
    }

    public async Task<bool> UpdateCultivoAsync(int id, CultivoUpdateViewModel viewModel)
    {
        if (!await _cultivoRepository.ExistsAsync(id))
        {
            return false;
        }
        var cultivoEntidad = new Cultivo { Nombre = viewModel.Nombre };
        return await _cultivoRepository.UpdateAsync(id, cultivoEntidad);
    }

    public async Task<bool> DeleteCultivoAsync(int id)
    {
        if (!await _cultivoRepository.ExistsAsync(id))
        {
            return false;
        }
        return await _cultivoRepository.DeleteAsync(id);
    }

    public async Task<bool> RestoreCultivoAsync(int id)
    {
        return await _cultivoRepository.RestoreAsync(id);
    }
}