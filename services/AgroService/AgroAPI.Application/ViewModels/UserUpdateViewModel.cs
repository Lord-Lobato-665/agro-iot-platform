using System.ComponentModel.DataAnnotations;

namespace AgroAPI.Application.ViewModels;

public class UserUpdateViewModel
{
    [Required]
    [StringLength(100)]
    public string Nombre { get; set; }

    [Phone]
    public string Telefono { get; set; }

    // Nota: No incluimos el correo (generalmente no se cambia)
    // ni la contraseña (debe tener su propio endpoint seguro).
}