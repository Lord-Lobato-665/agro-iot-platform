using AgroAPI.Application.Interfaces;
using AgroAPI.Application.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;

namespace AgroAPI.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ParcelasController : ControllerBase
{
    private readonly IParcelaService _parcelaService;

    public ParcelasController(IParcelaService parcelaService)
    {
        _parcelaService = parcelaService;
    }

    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetAll([FromQuery] bool includeDeleted = false)
    {
        var parcelas = await _parcelaService.GetAllParcelasAsync(includeDeleted);
        return Ok(parcelas);
    }

    [HttpGet("{id}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetById(Guid id)
    {
        var parcela = await _parcelaService.GetParcelaByIdAsync(id);
        if (parcela == null)
        {
            return NotFound($"No se encontró la parcela con ID: {id}");
        }
        return Ok(parcela);
    }

    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Create([FromBody] ParcelaCreateViewModel parcelaViewModel)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var nuevaParcelaDto = await _parcelaService.CreateParcelaAsync(parcelaViewModel);
        
        return CreatedAtAction(nameof(GetById), new { id = nuevaParcelaDto.Id }, nuevaParcelaDto);
    }

    [HttpPut("{id}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Update(Guid id, [FromBody] ParcelaUpdateViewModel parcelaViewModel)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var resultado = await _parcelaService.UpdateParcelaAsync(id, parcelaViewModel);

        if (!resultado)
        {
            return NotFound($"No se encontró la parcela con ID: {id} para actualizar.");
        }

        return NoContent(); // Estándar REST para un PUT exitoso
    }

    [HttpDelete("{id}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(Guid id)
    {
        var resultado = await _parcelaService.DeleteParcelaAsync(id);

        if (!resultado)
        {
            return NotFound($"No se encontró la parcela con ID: {id} para eliminar.");
        }

        return NoContent(); // Estándar REST para un DELETE exitoso
    }

    [HttpPatch("{id}/restore")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Restore(Guid id)
    {
        var resultado = await _parcelaService.RestoreParcelaAsync(id);

        if (!resultado)
        {
            return NotFound($"No se encontró una parcela eliminada con ID: {id} para restaurar.");
        }

        return NoContent(); // Éxito, sin contenido que devolver.
    }
}