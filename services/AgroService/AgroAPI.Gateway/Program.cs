using Ocelot.DependencyInjection;
using Ocelot.Middleware;

var builder = WebApplication.CreateBuilder(args);

// 1. Cargamos la configuración de ocelot.json
builder.Configuration.AddJsonFile("ocelot.json", optional: false, reloadOnChange: true);

// 2. Añadimos los servicios de Ocelot
builder.Services.AddOcelot(builder.Configuration);

var app = builder.Build();

// 3. Le decimos a la aplicación que use el middleware de Ocelot
await app.UseOcelot();

app.Run();