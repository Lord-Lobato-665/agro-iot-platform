using AgroAPI.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace AgroAPI.Infrastructure.Data;

public class ApplicationDbContext : DbContext
{
    // Este constructor es VITAL. Permite que la configuración de la conexión
    // (que haremos en Program.cs) sea "inyectada" en el DbContext.
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options)
    {
    }

    // Cada DbSet<T> representa una tabla en la base de datos.
    public DbSet<Cultivo> Cultivos { get; set; }
    public DbSet<Parcela> Parcelas { get; set; }
    public DbSet<Usuario> Usuarios { get; set; }
    
    // También incluimos las tablas pivote como DbSets
    public DbSet<ParcelaCultivo> ParcelaCultivos { get; set; }
    public DbSet<ParcelaUsuario> ParcelaUsuarios { get; set; }

    // Aquí configuramos las relaciones complejas usando la "Fluent API".
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Parcela>().HasQueryFilter(p => !p.IsDeleted);
        modelBuilder.Entity<Cultivo>().HasQueryFilter(c => !c.IsDeleted);
        modelBuilder.Entity<Usuario>().HasQueryFilter(u => !u.IsDeleted);

        // Configuración de la relación Muchos a Muchos entre Parcela y Cultivo
        modelBuilder.Entity<ParcelaCultivo>()
            .HasKey(pc => new { pc.ParcelaId, pc.CultivoId }); // Clave primaria compuesta

        modelBuilder.Entity<ParcelaCultivo>()
            .HasOne(pc => pc.Parcela)
            .WithMany(p => p.ParcelaCultivos)
            .HasForeignKey(pc => pc.ParcelaId);

        modelBuilder.Entity<ParcelaCultivo>()
            .HasOne(pc => pc.Cultivo)
            .WithMany(c => c.ParcelaCultivos)
            .HasForeignKey(pc => pc.CultivoId);

        // Configuración de la relación Muchos a Muchos entre Parcela y Usuario
        modelBuilder.Entity<ParcelaUsuario>()
            .HasKey(pu => new { pu.ParcelaId, pu.UsuarioId }); // Clave primaria compuesta

        modelBuilder.Entity<ParcelaUsuario>()
            .HasOne(pu => pu.Parcela)
            .WithMany(p => p.ParcelaUsuarios)
            .HasForeignKey(pu => pu.ParcelaId);

        modelBuilder.Entity<ParcelaUsuario>()
            .HasOne(pu => pu.Usuario)
            .WithMany(u => u.ParcelaUsuarios)
            .HasForeignKey(pu => pu.UsuarioId);
    }
}