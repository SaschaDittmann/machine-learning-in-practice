using System;

namespace TestDeployedRModels.Config
{
    public class MachineLearningServer
    {
        public static readonly Uri Url = new Uri("http://<vm-name>.<region>.cloudapp.azure.com:12800");
        public const string User = "admin";
        public const string Password = "<password>";
    }
}
