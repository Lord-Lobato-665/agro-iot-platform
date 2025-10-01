namespace AgroAPI.Domain.Entities;

public class Cultivo
{
    public int Id { get; set; }
    public string Nombre { get; set; }
    public bool IsDeleted { get; set; }
    
    // Propiedad de navegación
    public ICollection<ParcelaCultivo> ParcelaCultivos { get; set; } = new List<ParcelaCultivo>();
}
