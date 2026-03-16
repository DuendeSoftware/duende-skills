// TestUsers.cs — Test users for development
using Duende.IdentityServer.Test;
using IdentityModel;
using System.Security.Claims;

public static class TestUsers
{
    public static List<TestUser> Users =>
    [
        new TestUser
        {
            SubjectId = "1",
            Username = "alice",
            Password = "alice",
            Claims =
            {
                new Claim(JwtClaimTypes.Name, "Alice Smith"),
                new Claim(JwtClaimTypes.Email, "alice@example.com"),
                new Claim(JwtClaimTypes.Role, "admin")
            }
        },
        new TestUser
        {
            SubjectId = "2",
            Username = "bob",
            Password = "bob",
            Claims =
            {
                new Claim(JwtClaimTypes.Name, "Bob Jones"),
                new Claim(JwtClaimTypes.Email, "bob@example.com"),
                new Claim(JwtClaimTypes.Role, "user")
            }
        }
    ];
}
