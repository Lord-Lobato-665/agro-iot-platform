using AgroAPI.Application.Interfaces;
using AgroAPI.Domain.Entities;
using AgroAPI.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace AgroAPI.Infrastructure.Repositories;

public class LoggingRepository : ILoggingRepository
{
    private readonly IServiceProvider _serviceProvider;

    public LoggingRepository(IServiceProvider serviceProvider)
    {
        _serviceProvider = serviceProvider;
    }

    public async Task<IEnumerable<LogEntry>> GetAllLogsAsync()
    {
        using var scope = _serviceProvider.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

        // Devolvemos los logs más recientes primero
        return await dbContext.LogEntries
                            .OrderByDescending(log => log.Timestamp)
                            .ToListAsync();
    }

    public async Task SaveLogAsync(LogEntry log)
    {
        using var scope = _serviceProvider.CreateScope();
        
        // Esta línea ahora usa el DbContext principal
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

        await dbContext.LogEntries.AddAsync(log);
        await dbContext.SaveChangesAsync();
    }
}