using Microsoft.AspNetCore.Authentication.JwtBearer;
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

// Verificación para evitar el error si la clave no está en appsettings.json
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


// --- OTROS SERVICIOS ---
builder.Services.AddHttpClient();
builder.Services.AddControllers();

builder.Services.AddOcelot(builder.Configuration)
    .AddPolly();

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll",
        policy =>
        {
            policy.AllowAnyOrigin()
                  .AllowAnyMethod()
                  .AllowAnyHeader();
        });
});

var app = builder.Build();

app.UseCors("AllowAll");
// --- PIPELINE DE MIDDLEWARE EXPLÍCITO ---
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

// Le decimos explícitamente a la aplicación que aquí terminan las rutas de los controladores
app.UseEndpoints(endpoints =>
{
    endpoints.MapControllers();
});

// Solo si la petición no coincidió con ningún controlador, llegará aquí.
await app.UseOcelot();

app.Run();