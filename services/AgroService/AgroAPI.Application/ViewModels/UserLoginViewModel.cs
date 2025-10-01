using System.ComponentModel.DataAnnotations;

namespace AgroAPI.Application.ViewModels;

public class UserLoginViewModel
{
    [Required]
    [EmailAddress]
    public string Correo { get; set; }

    [Required]
    public string Password { get; set; }
}