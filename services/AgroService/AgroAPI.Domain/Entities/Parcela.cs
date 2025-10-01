namespace AgroAPI.Domain.Entities;

public class Parcela
{
    public Guid Id { get; set; }
    public string Nombre { get; set; }
    public double Latitud { get; set; }
    public double Longitud { get; set; }
    public int CantidadCultivos { get; set; }

    // Nueva propiedad para el borrado lógico
    public bool IsDeleted { get; set; } 
    
    public ICollection<ParcelaCultivo> ParcelaCultivos { get; set; } = new List<ParcelaCultivo>();
    public ICollection<ParcelaUsuario> ParcelaUsuarios { get; set; } = new List<ParcelaUsuario>();
}