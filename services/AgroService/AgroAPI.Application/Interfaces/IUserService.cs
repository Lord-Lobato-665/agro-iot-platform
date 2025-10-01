using AgroAPI.Application.DTOs;
using AgroAPI.Application.ViewModels;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace AgroAPI.Application.Interfaces;

public interface IUserService
{
    Task<UserDto?> GetUserByIdAsync(int id);
    Task<IEnumerable<UserDto>> GetAllUsersAsync(bool includeDeleted);
    Task<bool> UpdateUserAsync(int id, UserUpdateViewModel viewModel);
    Task<bool> DeleteUserAsync(int id);
    Task<bool> RestoreUserAsync(int id);
}