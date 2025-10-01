using AgroAPI.Application.DTOs;
using AgroAPI.Application.Interfaces;
using AgroAPI.Application.ViewModels;
using AgroAPI.Domain.Entities;

namespace AgroAPI.Application.Services;

public class ParcelaService : IParcelaService
{
    private readonly IParcelaRepository _parcelaRepository;

    public ParcelaService(IParcelaRepository parcelaRepository)
    {
        _parcelaRepository = parcelaRepository;
    }
    
    public Task<IEnumerable<ParcelaDto>> GetAllParcelasAsync(bool includeDeleted)
    {
        // Simplemente pasamos el parámetro al repositorio
        return _parcelaRepository.GetAllAsync(includeDeleted);
    }

    public Task<ParcelaDto?> GetParcelaByIdAsync(Guid id)
    {
        return _parcelaRepository.GetByIdAsync(id);
    }

    public async Task<ParcelaDto> CreateParcelaAsync(ParcelaCreateViewModel viewModel)
    {
        // Mapeo manual de ViewModel a Entidad
        var parcelaEntidad = new Parcela
        {
            Nombre = viewModel.Nombre,
            Latitud = viewModel.Latitud,
            Longitud = viewModel.Longitud
        };

        var nuevaParcela = await _parcelaRepository.CreateAsync(parcelaEntidad, viewModel.CultivosIds);

        // Tras crear, consultamos para obtener el DTO completo con los nombres de cultivos
        return await _parcelaRepository.GetByIdAsync(nuevaParcela.Id);
    }

    public async Task<bool> UpdateParcelaAsync(Guid id, ParcelaUpdateViewModel viewModel)
    {
        // Verificamos si la parcela existe antes de intentar actualizar
        if (!await _parcelaRepository.ExistsAsync(id))
        {
            return false;
        }

        // Mapeo manual de ViewModel a Entidad para la actualización
        var parcelaEntidad = new Parcela
        {
            Nombre = viewModel.Nombre,
            Latitud = viewModel.Latitud,
            Longitud = viewModel.Longitud
        };

        return await _parcelaRepository.UpdateAsync(id, parcelaEntidad, viewModel.CultivosIds);
    }

    public async Task<bool> DeleteParcelaAsync(Guid id)
    {
        // Verificamos si la parcela existe antes de intentar borrar
        if (!await _parcelaRepository.ExistsAsync(id))
        {
            return false;
        }
        
        return await _parcelaRepository.DeleteAsync(id);
    }

    public async Task<bool> RestoreParcelaAsync(Guid id)
    {
        // La lógica de negocio es simple: solo llamamos al repositorio.
        // La validación de si existe o no ya la maneja la capa inferior.
        return await _parcelaRepository.RestoreAsync(id);
    }
}