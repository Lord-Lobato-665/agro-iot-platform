using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json.Linq;
using System.Linq;
using System.Net.Http.Headers;
using System.Threading.Tasks;

namespace AgroAPI.Gateway.Controllers;

[ApiController]
[Route("parcela-detallada")]
public class ParcelaDetalladaController : ControllerBase
{
    private readonly IHttpClientFactory _httpClientFactory;

    public ParcelaDetalladaController(IHttpClientFactory httpClientFactory)
    {
        _httpClientFactory = httpClientFactory;
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> Get(string id)
    {
        var client = _httpClientFactory.CreateClient();

        // 1. Reenviar el token de autorización de forma segura
        if (Request.Headers.TryGetValue("Authorization", out var authHeaderValues))
        {
            var authHeader = authHeaderValues.FirstOrDefault();
            if (!string.IsNullOrEmpty(authHeader))
            {
                client.DefaultRequestHeaders.Authorization = AuthenticationHeaderValue.Parse(authHeader);
            }
        }

        // 2. Llamar a ambos microservicios en paralelo
    // Use container hostnames so the gateway container can reach downstream services in the compose network
    var parcelaTask = client.GetAsync($"http://agroapi-api:8081/api/parcelas/{id}");
    var sensoresTask = client.GetAsync($"http://api-services:3001/api/sensores/by-parcela/{id}");

        await Task.WhenAll(parcelaTask, sensoresTask);

        var parcelaResponse = await parcelaTask;
        var sensoresResponse = await sensoresTask;

        // 3. Verificamos la respuesta de la parcela
        if (parcelaResponse.StatusCode == System.Net.HttpStatusCode.Unauthorized)
        {
            return Unauthorized();
        }
        if (!parcelaResponse.IsSuccessStatusCode)
        {
            return NotFound($"No se encontró la parcela con el ID: {id}");
        }

        // 4. Leemos y combinamos el contenido
        var parcelaContent = await parcelaResponse.Content.ReadAsStringAsync();
        var sensoresContent = sensoresResponse.IsSuccessStatusCode 
            ? await sensoresResponse.Content.ReadAsStringAsync() 
            : "[]"; 

        var parcelaJson = JObject.Parse(parcelaContent);
        var sensoresJson = JArray.Parse(sensoresContent);

        parcelaJson["sensores"] = sensoresJson;

        return Ok(parcelaJson);
    }
}