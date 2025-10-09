using AgroAPI.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace AgroAPI.Infrastructure.Data;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options)
    {
    }

    // DbSets de la aplicación principal
    public DbSet<Cultivo> Cultivos { get; set; }
    public DbSet<Parcela> Parcelas { get; set; }
    public DbSet<Usuario> Usuarios { get; set; }
    public DbSet<ParcelaCultivo> ParcelaCultivos { get; set; }
    public DbSet<ParcelaUsuario> ParcelaUsuarios { get; set; }
    public DbSet<Rol> Roles { get; set; }
    public DbSet<UsuarioRol> UsuarioRoles { get; set; }
    public DbSet<LogEntry> LogEntries { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // --- Filtros de borrado lógico ---
        modelBuilder.Entity<Parcela>().HasQueryFilter(p => !p.IsDeleted);
        modelBuilder.Entity<Cultivo>().HasQueryFilter(c => !c.IsDeleted);
        modelBuilder.Entity<Usuario>().HasQueryFilter(u => !u.IsDeleted);

        // --- Configuración de relaciones M-M ---
        modelBuilder.Entity<ParcelaCultivo>()
            .HasKey(pc => new { pc.ParcelaId, pc.CultivoId });

        modelBuilder.Entity<ParcelaCultivo>()
            .HasOne(pc => pc.Parcela)
            .WithMany(p => p.ParcelaCultivos)
            .HasForeignKey(pc => pc.ParcelaId);

        modelBuilder.Entity<ParcelaCultivo>()
            .HasOne(pc => pc.Cultivo)
            .WithMany(c => c.ParcelaCultivos)
            .HasForeignKey(pc => pc.CultivoId);

        modelBuilder.Entity<ParcelaUsuario>()
            .HasKey(pu => new { pu.ParcelaId, pu.UsuarioId });

        modelBuilder.Entity<ParcelaUsuario>()
            .HasOne(pu => pu.Parcela)
            .WithMany(p => p.ParcelaUsuarios)
            .HasForeignKey(pu => pu.ParcelaId);

        modelBuilder.Entity<ParcelaUsuario>()
            .HasOne(pu => pu.Usuario)
            .WithMany(u => u.ParcelaUsuarios)
            .HasForeignKey(pu => pu.UsuarioId);

        // Configuracion para los roles

        // 1. Definir la clave primaria compuesta para la tabla de unión
        modelBuilder.Entity<UsuarioRol>()
            .HasKey(ur => new { ur.UsuarioId, ur.RolId });

        // 2. Definir las relaciones
        modelBuilder.Entity<UsuarioRol>()
            .HasOne(ur => ur.Usuario)
            .WithMany(u => u.UsuarioRoles)
            .HasForeignKey(ur => ur.UsuarioId);

        modelBuilder.Entity<UsuarioRol>()
            .HasOne(ur => ur.Rol)
            .WithMany(r => r.UsuarioRoles)
            .HasForeignKey(ur => ur.RolId);

        // 3. SEMBRAR DATOS (Seed Data): Crear los roles por defecto
        modelBuilder.Entity<Rol>().HasData(
            new Rol { Id = 1, Nombre = "Admin" },
            new Rol { Id = 2, Nombre = "User" }
        );
    }
}