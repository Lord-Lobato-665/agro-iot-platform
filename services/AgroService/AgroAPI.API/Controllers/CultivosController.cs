using AgroAPI.Application.Interfaces;
using AgroAPI.Application.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;

namespace AgroAPI.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CultivosController : ControllerBase
{
    private readonly ICultivoService _cultivoService;

    public CultivosController(ICultivoService cultivoService)
    {
        _cultivoService = cultivoService;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] bool includeDeleted = false)
    {
        var cultivos = await _cultivoService.GetAllCultivosAsync(includeDeleted);
        return Ok(cultivos);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        var cultivo = await _cultivoService.GetCultivoByIdAsync(id);
        if (cultivo == null)
        {
            return NotFound();
        }
        return Ok(cultivo);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CultivoCreateViewModel viewModel)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }
        var nuevoCultivo = await _cultivoService.CreateCultivoAsync(viewModel);
        return CreatedAtAction(nameof(GetById), new { id = nuevoCultivo.Id }, nuevoCultivo);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(int id, [FromBody] CultivoUpdateViewModel viewModel)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }
        var resultado = await _cultivoService.UpdateCultivoAsync(id, viewModel);
        if (!resultado)
        {
            return NotFound();
        }
        return NoContent();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id)
    {
        var resultado = await _cultivoService.DeleteCultivoAsync(id);
        if (!resultado)
        {
            return NotFound();
        }
        return NoContent();
    }

    [HttpPatch("{id}/restore")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Restore(int id)
    {
        var resultado = await _cultivoService.RestoreCultivoAsync(id);

        if (!resultado)
        {
            return NotFound($"No se encontró un cultivo eliminado con ID: {id} para restaurar.");
        }

        return NoContent();
    }
}