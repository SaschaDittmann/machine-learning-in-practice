using System;

namespace TestDeployedRModels.Config
{
    public class CarSvcContainerInstance
    {
        public static readonly Uri ManualTransmissionEndpoint = new Uri("http://<dns-name-label>.<region>.azurecontainer.io:8000/manualtransmission");
    }
}
