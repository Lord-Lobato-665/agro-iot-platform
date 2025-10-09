using System.ComponentModel.DataAnnotations;
using System.Collections.Generic;

namespace AgroAPI.Application.ViewModels;

public class UserUpdateViewModel
{
    [Required]
    [StringLength(100)]
    public string Nombre { get; set; }

    [Phone]
    public string Telefono { get; set; }

    public List<int> RolesIds { get; set; } = new List<int>();
}