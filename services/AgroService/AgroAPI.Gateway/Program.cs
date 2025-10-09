using AgroAPI.Application.Interfaces;
using AgroAPI.Application.Services;
using AgroAPI.Gateway.Middleware;
using AgroAPI.Infrastructure.Data;
using AgroAPI.Infrastructure.Repositories;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Ocelot.DependencyInjection;
using Ocelot.Middleware;
using Ocelot.Provider.Polly;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

builder.Configuration.AddJsonFile("ocelot.json", optional: false, reloadOnChange: true);

// --- CONFIGURACIÓN DE JWT ---
var jwtSettings = builder.Configuration.GetSection("Jwt");
var keyString = jwtSettings["Key"];

if (string.IsNullOrEmpty(keyString))
{
    throw new ArgumentNullException(nameof(keyString), "La clave JWT (Jwt:Key) no puede ser nula o vacía en appsettings.json");
}

var key = Encoding.UTF8.GetBytes(keyString);

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer("Bearer", options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = jwtSettings["Issuer"],
        ValidAudience = jwtSettings["Audience"],
        IssuerSigningKey = new SymmetricSecurityKey(key)
    };
});

// --- CONFIGURACIÓN DE SERVICIOS UNIFICADA ---
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddSingleton<ILoggingService, LoggingService>();
builder.Services.AddSingleton<ILoggingRepository, LoggingRepository>();

builder.Services.AddHttpClient();
builder.Services.AddControllers();
builder.Services.AddOcelot(builder.Configuration).AddPolly();
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll",
        policy =>
        {
            policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader();
        });
});

var app = builder.Build();

// --- PIPELINE DE MIDDLEWARE ---
app.UseMiddleware<RequestLoggingMiddleware>();
app.UseCors("AllowAll");
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();
app.UseEndpoints(endpoints =>
{
    endpoints.MapControllers();
});
await app.UseOcelot();

app.Run();