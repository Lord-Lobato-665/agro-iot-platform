using AgroAPI.Application.ViewModels;
using System.Threading.Tasks;

namespace AgroAPI.Application.Interfaces;

public interface IAuthService
{
    Task<bool> RegisterAsync(UserRegisterViewModel model);
    Task<string?> LoginAsync(UserLoginViewModel model);
}