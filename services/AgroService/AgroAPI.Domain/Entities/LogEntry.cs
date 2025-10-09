
namespace AgroAPI.Domain.Entities;

public class LogEntry
{
    public long Id { get; set; }
    public string RequestPath { get; set; }
    public string RequestMethod { get; set; }
    public int ResponseStatusCode { get; set; }
    public string RequestBody { get; set; }
    public string ResponseBody { get; set; }
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}