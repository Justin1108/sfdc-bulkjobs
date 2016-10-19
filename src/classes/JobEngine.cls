public with sharing class JobEngine {
	public static final String Job_Name = 'BulkJob.MaxQueueJob';
	public static final String Cron_Exp = '0 0 * ? * ? *'; // Schedule every hour

	public enum Priority { High, Medium, Low }


	public JobEngine() {
		
	}

	public Id addJob(Priority p, String processorName, List<String> recs) {
		Job_Queue__c job = new Job_Queue__c(
			Priority__c = getPriorityVal(p),
			Processor__c = processorName,
			Request__c = String.join(recs, ','),
			Status__c = 'Ready'
			);

		insert job;

		return job.Id;
	}

	/*
	 * Start the engine
	 */
	public void start() {
		Datetime nextFireTime;
		CronTrigger[] ctList = [SELECT Id, CronJobDetail.Id, CronJobDetail.Name, NextFireTime FROM CronTrigger WHERE CronJobDetail.Name LIKE :Job_Name + '%'];
		if (ctList.size() == 0) {
			System.schedule(Job_Name, Cron_Exp, new JobScheduler());
			CronTrigger ct = [SELECT Id, CronJobDetail.Id, CronJobDetail.Name, NextFireTime FROM CronTrigger WHERE CronJobDetail.Name = :Job_Name];
			nextFireTime = ct.NextFireTime;
		} else {
			for (CronTrigger ct : ctList) {
				if (nextFireTime == null || nextFireTime > ct.NextFireTime) {
					nextFireTime = ct.NextFireTime;
				}
			}
		}

		if (Datetime.now().addMinutes(5) < nextFireTime) {
			// Next run is five more minutes later, just schedule a one-time one in 15 seconds
			nextFireTime = Datetime.now().addSeconds(15);
			String sch = nextFireTime.second() + ' ' + nextFireTime.minute() + ' ' + nextFireTime.hour() + ' ' + nextFireTime.day() + ' ' + nextFireTime.month() + ' ? ' + nextFireTime.year();
			String jobName = Job_Name + ' - ' + nextFireTime.formatLong();

			System.schedule(Job_Name, Cron_Exp, new JobScheduler(false));
		}


	}

	/*
	 * Start the engine
	 */
	public void stop() {
		CronTrigger[] ctList = [SELECT Id, CronJobDetail.Id, CronJobDetail.Name, NextFireTime FROM CronTrigger WHERE CronJobDetail.Name LIKE :Job_Name + '%'];
		for (CronTrigger ct : ctList) {
			System.abortJob(ct.Id);
		}
	}

	/*
	 * Helper method to acquired a lock
	 */
	public static Boolean lock(String lockName) {
		try {
			Lock__c[] locks = [SELECT Id FROM Lock__c WHERE Key__c = :lockName FOR UPDATE];
			if (locks.size() == 0) {
				Lock__c lock = new Lock__c(
					Key__c = lockName
					);
				insert lock;
				locks = [SELECT Id FROM Lock__c WHERE Key__c = :lockName FOR UPDATE];
			}

			return true;
		} catch (QueryException ex) {
			// {lockName} is locked
			return false;
 		} catch (Exception ex) {
 			// General ex
 			return false;
 		}
	}



	Integer getPriorityVal(Priority p) {
		if (p == Priority.High) return 2;
		else if (p == Priority.Medium) return 1;
		else return 0;
	}
}