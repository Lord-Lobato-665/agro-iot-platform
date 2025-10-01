using AgroAPI.Domain.Entities;
using System.Threading.Tasks;
using AgroAPI.Application.DTOs;
using System.Collections.Generic;

namespace AgroAPI.Application.Interfaces;

public interface IUserRepository
{
    Task<Usuario?> GetUserByEmailAsync(string email);
    Task AddUserAsync(Usuario user);
    Task<UserDto?> GetByIdAsync(int id);
    Task<IEnumerable<UserDto>> GetAllAsync(bool includeDeleted);
    Task<bool> UpdateAsync(int id, Usuario user);
    Task<bool> DeleteAsync(int id);
    Task<bool> RestoreAsync(int id);
}