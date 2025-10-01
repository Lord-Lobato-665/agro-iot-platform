namespace AgroAPI.Domain.Entities;

public class ParcelaUsuario
{
    public Guid ParcelaId { get; set; }
    public Parcela Parcela { get; set; }
    
    public int UsuarioId { get; set; }
    public Usuario Usuario { get; set; }
}