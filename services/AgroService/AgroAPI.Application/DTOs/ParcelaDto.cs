namespace AgroAPI.Application.DTOs;

public class ParcelaDto
{
    public Guid Id { get; set; }
    public string Nombre { get; set; }
    public double Latitud { get; set; }
    public double Longitud { get; set; }
    public int CantidadCultivos { get; set; }
    public List<string> NombresCultivos { get; set; } = new List<string>();
    
    // Propiedad añadida
    public bool IsDeleted { get; set; } 
}