using IdentityServer4.EntityFramework.DbContexts;
using IdentityServer4.EntityFramework.Mappers;
using IdentityServer4.Models;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using System;
using System.Linq;
using System.Security.Claims;

namespace IdentityServerMigrationSample
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var provider = CreateHostBuilder(args).Build().Services;
            using (var scope = provider.CreateScope())
            {
                var grants = scope.ServiceProvider.GetRequiredService<PersistedGrantDbContext>();
                grants.Database.Migrate();
                
                var config = scope.ServiceProvider.GetRequiredService<ConfigurationDbContext>();
                config.Database.Migrate();
            }
        }

        public static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .ConfigureWebHostDefaults(webBuilder =>
                {
                    webBuilder.UseStartup<Startup>();
                });
    }
}
