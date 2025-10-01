namespace AgroAPI.Domain.Entities;

public class ParcelaCultivo
{
    public Guid ParcelaId { get; set; }
    public Parcela Parcela { get; set; }
    
    public int CultivoId { get; set; }
    public Cultivo Cultivo { get; set; }
}