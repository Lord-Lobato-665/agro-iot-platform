
using System.Collections.Generic;
namespace AgroAPI.Application.DTOs;

public class UserDto
{
    public int Id { get; set; }
    public string Nombre { get; set; }
    public string Correo { get; set; }
    public string Telefono { get; set; }
    public bool IsDeleted { get; set; }

    public List<string> Roles { get; set; } = new List<string>();
}