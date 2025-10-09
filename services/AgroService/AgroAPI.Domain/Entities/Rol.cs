
using System.Collections.Generic;
namespace AgroAPI.Domain.Entities;

public class Rol
{
    public int Id { get; set; }
    public string Nombre { get; set; }

    public ICollection<UsuarioRol> UsuarioRoles { get; set; } = new List<UsuarioRol>();
}