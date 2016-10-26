using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Azure; // Namespace for CloudConfigurationManager
using Microsoft.WindowsAzure.Storage; // Namespace for CloudStorageAccount
using Microsoft.WindowsAzure.Storage.Queue;

namespace QueuePublisher
{
    class Program
    {
        static void Main(string[] args)
        {
            while (true)
            {
                AddMessageinQueue("message", "microscaling-demo");
                System.Threading.Thread.Sleep(new TimeSpan(0, 0, 5));
            }
        }
        public static bool AddMessageinQueue(string MessageToAdd, string QueueName)
        {
            try
            {
                CloudStorageAccount account = CloudStorageAccount.Parse("DefaultEndpointsProtocol=https;AccountName=microscale;AccountKey=Ue6nybNleYIFDHB382Cn9FbzJDu66ewmIyzO9q5uAhlCe9L8IGEk9ReVp/xp6MQlJrpCeDSmTe/fbe7Lbp97qQ==");
                CloudQueueClient queueClient = account.CreateCloudQueueClient();
                CloudQueue queue = queueClient.GetQueueReference(QueueName);

                CloudQueueMessage m = new CloudQueueMessage(MessageToAdd);
                queue.AddMessage(m);


                return true;

            }
            catch (Exception ex)
            {
                return false;
            }
        }

    }
}
