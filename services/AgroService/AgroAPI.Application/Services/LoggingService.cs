using AgroAPI.Application.Interfaces;
using AgroAPI.Domain.Entities;
using System.Threading.Tasks;

namespace AgroAPI.Application.Services;

public class LoggingService : ILoggingService
{
    private readonly ILoggingRepository _loggingRepository;

    public LoggingService(ILoggingRepository loggingRepository)
    {
        _loggingRepository = loggingRepository;
    }

    public Task<IEnumerable<LogEntry>> GetAllLogsAsync()
    {
        return _loggingRepository.GetAllLogsAsync();
    }

    public Task SaveLogAsync(LogEntry log)
    {
        // La lógica de negocio es simple: delega la tarea de guardar al repositorio.
        return _loggingRepository.SaveLogAsync(log);
    }
}