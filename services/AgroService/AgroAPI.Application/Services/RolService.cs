using AgroAPI.Application.DTOs;
using AgroAPI.Application.Interfaces;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace AgroAPI.Application.Services;

public class RolService : IRolService
{
    private readonly IRolRepository _rolRepository;

    public RolService(IRolRepository rolRepository)
    {
        _rolRepository = rolRepository;
    }

    public Task<IEnumerable<RolDto>> GetAllRolesAsync()
    {
        return _rolRepository.GetAllRolesAsync();
    }
}