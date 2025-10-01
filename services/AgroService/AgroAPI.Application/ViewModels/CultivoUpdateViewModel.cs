using System.ComponentModel.DataAnnotations;

namespace AgroAPI.Application.ViewModels;

public class CultivoUpdateViewModel
{
    [Required(ErrorMessage = "El nombre del cultivo es obligatorio.")]
    [StringLength(50, ErrorMessage = "El nombre no puede exceder los 50 caracteres.")]
    public string Nombre { get; set; }
}