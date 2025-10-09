using AgroAPI.Application.DTOs;
using AgroAPI.Application.Interfaces;
using AgroAPI.Application.ViewModels;
using AgroAPI.Domain.Entities;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace AgroAPI.Application.Services;

public class UserService : IUserService
{
    private readonly IUserRepository _userRepository;

    public UserService(IUserRepository userRepository)
    {
        _userRepository = userRepository;
    }

    public Task<UserDto?> GetUserByIdAsync(int id)
    {
        return _userRepository.GetByIdAsync(id);
    }
    
    public Task<IEnumerable<UserDto>> GetAllUsersAsync(bool includeDeleted)
    {
        return _userRepository.GetAllAsync(includeDeleted);
    }

    public Task<bool> UpdateUserAsync(int id, UserUpdateViewModel viewModel)
    {
        var user = new Usuario
        {
            Nombre = viewModel.Nombre,
            Telefono = viewModel.Telefono
        };
        // Pasamos la lista de IDs de roles al repositorio
        return _userRepository.UpdateAsync(id, user, viewModel.RolesIds);
    }

    public Task<bool> DeleteUserAsync(int id)
    {
        return _userRepository.DeleteAsync(id);
    }

    public Task<bool> RestoreUserAsync(int id)
    {
        return _userRepository.RestoreAsync(id);
    }
}