using System.ComponentModel.DataAnnotations;

namespace AgroAPI.Application.ViewModels;

public class ParcelaCreateViewModel
{
    [Required(ErrorMessage = "El nombre es obligatorio.")]
    [StringLength(100)]
    public string Nombre { get; set; }

    [Range(-90, 90)]
    public double Latitud { get; set; }

    [Range(-180, 180)]
    public double Longitud { get; set; }
    
    public List<int> CultivosIds { get; set; } = new List<int>();
}