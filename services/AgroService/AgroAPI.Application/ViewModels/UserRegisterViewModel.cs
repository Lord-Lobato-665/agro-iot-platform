using System.ComponentModel.DataAnnotations;

namespace AgroAPI.Application.ViewModels;

public class UserRegisterViewModel
{
    [Required]
    [StringLength(100)]
    public string Nombre { get; set; }

    [Required]
    [EmailAddress]
    public string Correo { get; set; }

    [Required]
    [MinLength(6)]
    public string Password { get; set; }
    
    public string Telefono { get; set; }
}