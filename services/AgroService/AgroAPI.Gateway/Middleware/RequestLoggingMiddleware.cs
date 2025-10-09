using AgroAPI.Application.Interfaces;
using AgroAPI.Domain.Entities;
using Microsoft.AspNetCore.Http;
using System;
using System.IO;
using System.Text;
using System.Threading.Tasks;

namespace AgroAPI.Gateway.Middleware;

public class RequestLoggingMiddleware
{
    private readonly RequestDelegate _next;

    public RequestLoggingMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context, ILoggingService loggingService)
    {
        // --- INICIO DE LA SECCIÓN DE CAPTURA (NO CAMBIA) ---
        context.Request.EnableBuffering();
        var requestBody = await new StreamReader(context.Request.Body, leaveOpen: true).ReadToEndAsync();
        context.Request.Body.Position = 0;

        var originalResponseBodyStream = context.Response.Body;
        using var responseBody = new MemoryStream();
        context.Response.Body = responseBody;

        // --- CONTINUAMOS CON EL PIPELINE ---
        await _next(context);

        // --- INICIO DE LA SECCIÓN DE LOGGING (A PRUEBA DE FALLOS) ---
        try
        {
            context.Response.Body.Seek(0, SeekOrigin.Begin);
            var responseBodyText = await new StreamReader(context.Response.Body).ReadToEndAsync();
            context.Response.Body.Seek(0, SeekOrigin.Begin);

            var logEntry = new LogEntry
            {
                RequestPath = context.Request.Path,
                RequestMethod = context.Request.Method,
                ResponseStatusCode = context.Response.StatusCode,
                RequestBody = requestBody,
                ResponseBody = responseBodyText,
                Timestamp = DateTime.UtcNow
            };

            // Intentamos guardar el log
            await loggingService.SaveLogAsync(logEntry);
        }
        catch (Exception ex)
        {
            // SI FALLA, LO MOSTRAMOS EN LA CONSOLA DEL GATEWAY
            Console.WriteLine("!!!!!!!!!!!! ERROR AL GUARDAR EL LOG !!!!!!!!!!!!");
            Console.WriteLine(ex.ToString());
            Console.WriteLine("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
        }
        finally
        {
            // ESTO SE EJECUTA SIEMPRE, para asegurar que el cliente reciba su respuesta
            await responseBody.CopyToAsync(originalResponseBodyStream);
        }
    }
}