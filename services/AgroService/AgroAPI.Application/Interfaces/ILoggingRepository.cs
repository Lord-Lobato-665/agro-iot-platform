using AgroAPI.Domain.Entities;
using System.Threading.Tasks;

namespace AgroAPI.Application.Interfaces;

public interface ILoggingRepository
{
    Task SaveLogAsync(LogEntry log);
    Task<IEnumerable<LogEntry>> GetAllLogsAsync();
}