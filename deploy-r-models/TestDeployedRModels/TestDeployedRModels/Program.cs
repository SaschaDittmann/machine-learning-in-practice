using System;
using System.Collections.Generic;
using System.Globalization;
using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.Rest;
using Newtonsoft.Json;
using TestDeployedRModels.Config;
using TestDeployedRModels.Models;

namespace TestDeployedRModels
{
    class Program
    {
        static void Main(string[] args)
        {
            MainAsync(args).GetAwaiter().GetResult();

            Console.ReadKey();
        }

        private static async Task MainAsync(string[] args)
        {
            try
            {
                var resultPlumber = await PlumberManualTransmission(120, 2.8);
                Console.WriteLine($"Plumber Result: {resultPlumber}");

                var resultMls = await MlsManualTransmission(120, 2.8);
                Console.WriteLine($"Machine Learning Server Result: {resultMls}");
            }
            catch (Exception e)
            {
                Console.WriteLine(e);
            }
        }

        private static async Task<double?> PlumberManualTransmission(double hp, double wt)
        {
            var client = new HttpClient();

            var values = new Dictionary<string, string>
            {
                { "hp", hp.ToString(CultureInfo.InvariantCulture) },
                { "wt", wt.ToString(CultureInfo.InvariantCulture) }
            };

            var content = new FormUrlEncodedContent(values);

            var response = await client.PostAsync(
                CarSvcContainerInstance.ManualTransmissionEndpoint, 
                content);

            var responseString = await response.Content.ReadAsStringAsync();

            var results = JsonConvert.DeserializeObject<double?[]>(responseString);

            return results.Length > 0 ? results[0] : null;
        }

        private static async Task<string> GetAccessToken()
        {
            var client = new CarsService(
                MachineLearningServer.Url, 
                new BasicAuthenticationCredentials());
            var loginRequest = new LoginRequest(
                MachineLearningServer.User,
                MachineLearningServer.Password);
            var loginResponse = await client.LoginAsync(loginRequest);
            return loginResponse.AccessToken;
        }

        private static async Task<double?> MlsManualTransmission(double hp, double wt)
        {
            var accessToken = await GetAccessToken();

            var auth = new TokenCredentials(accessToken);
            var client = new CarsService(
                MachineLearningServer.Url, auth);

            var result = await client.ManualTransmissionAsync(
                new InputParameters(hp, wt));
            if (result.Success.HasValue && result.Success.Value)
                return result.OutputParameters.Answer;

            return null;
        }
    }
}
