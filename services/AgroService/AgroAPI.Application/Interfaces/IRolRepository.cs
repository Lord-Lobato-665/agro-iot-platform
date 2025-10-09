using AgroAPI.Domain.Entities;
using System.Threading.Tasks;
using AgroAPI.Application.DTOs;
using System.Collections.Generic;
using System.Linq;

namespace AgroAPI.Application.Interfaces;

public interface IRolRepository
{
    Task<Rol?> GetRolByNameAsync(string name);
    Task<IEnumerable<RolDto>> GetAllRolesAsync();
}