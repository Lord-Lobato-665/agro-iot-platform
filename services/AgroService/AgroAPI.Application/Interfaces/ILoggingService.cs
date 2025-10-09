// AgroAPI.Application/Interfaces/ILoggingService.cs
using AgroAPI.Domain.Entities;

public interface ILoggingService
{
    Task SaveLogAsync(LogEntry log);
    Task<IEnumerable<LogEntry>> GetAllLogsAsync();
}