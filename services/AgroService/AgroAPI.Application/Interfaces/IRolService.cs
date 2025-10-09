using AgroAPI.Application.DTOs;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace AgroAPI.Application.Interfaces;

public interface IRolService
{
    Task<IEnumerable<RolDto>> GetAllRolesAsync();
}