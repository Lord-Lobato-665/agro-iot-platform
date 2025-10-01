using System.ComponentModel.DataAnnotations;

namespace AgroAPI.Application.ViewModels;

public class ParcelaUpdateViewModel
{
    [Required(ErrorMessage = "El nombre es obligatorio.")]
    [StringLength(100, ErrorMessage = "El nombre no puede exceder los 100 caracteres.")]
    public string Nombre { get; set; }

    [Range(-90, 90, ErrorMessage = "La latitud debe estar entre -90 y 90.")]
    public double Latitud { get; set; }

    [Range(-180, 180, ErrorMessage = "La longitud debe estar entre -180 y 180.")]
    public double Longitud { get; set; }
    
    // Al actualizar, también permitimos modificar la lista de cultivos
    public List<int> CultivosIds { get; set; } = new List<int>();
}