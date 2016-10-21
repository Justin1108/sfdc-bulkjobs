global without sharing class JobScheduler implements Schedulable {
	public static Integer Max_Queued_Job_Count = 50;
	Boolean isRepeatJob;

	public JobScheduler() {
		this(true);
	}

	public JobScheduler(Boolean isRepeatJob) {
		this.isRepeatJob = isRepeatJob;
	}

	global void execute(SchedulableContext sc) {
		System.debug(LoggingLevel.DEBUG, 'Enter JobScheduler.execute');
		System.debug(LoggingLevel.DEBUG, 'isRepeatJob: ' + String.valueOf(isRepeatJob));

		if (JobEngine.lock('JobQueue')) {
			Integer totalJobCount = Limits.getQueueableJobs(); // [SELECT Count() FROM AsyncApexJob WHERE JobType='Queueable' AND Status IN ('Queued', 'Preparing', 'Processing')];
			Integer availJobCount = Max_Queued_Job_Count - totalJobCount;

			System.debug('totalJobCount: ' + totalJobCount + ', availJobCount: ' + availJobCount);
			if (availJobCount > 0) {
				Job_Queue__c[] readyJobs = [SELECT Request__c, Processor__c FROM Job_Queue__c WHERE Status__c='Ready' ORDER BY Priority__c Desc, CreatedDate LIMIT :availJobCount];
				System.debug('totalJobCount: ' + totalJobCount + ', availJobCount: ' + availJobCount);

				Job_Queue__c[] jobsToUpdate = new List<Job_Queue__c>();
				for (Job_Queue__c job : readyJobs) {
					try {
						//Type processorType = Type.forName(job.Processor__c);
						//IJobProcessor processor = (IJobProcessor)processorType.newInstance();
						//Queueable queueProc = (Queueable)processor;

						//System.enqueueJob(queueProc);

						System.enqueueJob(new JobProcessor(job.Id, job.Request__c.split(','), 0, job.Processor__c));

						jobsToUpdate.add(new Job_Queue__c(
							Id = job.Id,
							Status__c = 'Running'
							));
					} catch (Exception ex) {
						jobsToUpdate.add(new Job_Queue__c(
							Id = job.Id,
							Status__c = 'Running',
							Response__c = ex.getMessage()
							));
					}
				}

				update jobsToUpdate;
			}
		}

		if (!isRepeatJob) { // Abort the one time job
			System.abortJob(sc.getTriggerId());
		}
		System.debug(LoggingLevel.DEBUG, 'Exit JobScheduler.execute');
	}
}