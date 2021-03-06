public with sharing class JobEngine {
	public static final String Job_Name = 'BulkJob.MaxQueueJob';
	public static final String Cron_Exp = '0 0 * * * ? *'; // Schedule every hour

	public class LockException extends Exception { }
	public class AppException extends Exception { }

	public enum Priority { High, Medium, Low }

	public JobEngine() {
		
	}

	@TestVisible
	static String getJobName() {
		if (Test.isRunningTest())
			return Job_Name + '_Test';
		else
			return Job_Name;
	}

	@TestVisible
	static String getRepeatJobName() {
		return getJobName() + ' - Hourly';
	}

	@TestVisible
	static String getOneTimeJobName(Datetime fireTime) {
		return getJobName() + ' - ' + fireTime.formatLong();
	}

	public static Integer getMaxBQueueJobs() {
		return 50;
	}

	public static Integer getSchedulerTimelag() {
		return 5;
	}

	static Id scheduleBQueueJob(Datetime nextFireTime) {
		String sch = nextFireTime.second() + ' ' + nextFireTime.minute() + ' ' + nextFireTime.hour() + ' ' + nextFireTime.day() + ' ' + nextFireTime.month() + ' ? ' + nextFireTime.year();
		String jobName = getOneTimeJobName(nextFireTime);

		return System.schedule(jobName, sch, new JobScheduler(false));				
	}

	public Id addJob(Priority p, String processorName, List<String> recs) {
		return addJob(p, processorName, null, null, recs);
	}

	public Id addJob(Priority p, String processorName, String para1, String para2, List<String> recs) {
		Type pt = Type.forName(processorName);
		if (pt == null)
			throw new AppException('The ' + processorName + ' class does not exist.');

		Object proc = pt.newInstance();

		if (proc instanceof IJobProcessor) {
			Job_Queue__c job = new Job_Queue__c(
				Priority__c = getPriorityVal(p),
				Processor__c = processorName,
				Request__c = String.join(recs, ','),
				Parameter_1__c = para1,
				Parameter_2__c = para2,
				Status__c = 'Ready'
				);

			insert job;

			return job.Id;
		} else {
			throw new AppException('The ' + processorName + ' class does not implement IJobProcessor or Queueable interface.');
		}
	}

	/*
	 * Start the engine
	 */
	public List<Id> start() {
		return start(Cron_Exp);
	}

	public List<Id> start(String cronExp) {
		List<Id> jobIds = new List<Id>();
		String jobName = getRepeatJobName();

		if (lock('JobScheduler')) {
			Datetime nextFireTime;
			CronTrigger[] ctList = [SELECT Id, CronJobDetail.Id, CronJobDetail.Name, NextFireTime FROM CronTrigger WHERE CronJobDetail.Name LIKE :getJobName() + '%'];
			if (ctList.size() == 0) {
				System.debug(cronExp);
				jobIds.add(System.schedule(jobName, cronExp, new JobScheduler()));
				CronTrigger ct = [SELECT Id, CronJobDetail.Id, CronJobDetail.Name, NextFireTime FROM CronTrigger WHERE CronJobDetail.Name = :jobName];
				nextFireTime = ct.NextFireTime;
			} else {
				for (CronTrigger ct : ctList) {
					if (nextFireTime == null || nextFireTime > ct.NextFireTime) {
						nextFireTime = ct.NextFireTime;
					}
				}
			}

			if (Datetime.now().addSeconds(getSchedulerTimelag()) < nextFireTime) {
				// Next run is five more minutes later, just schedule a one-time one in 15 seconds
				nextFireTime = Datetime.now().addSeconds(getSchedulerTimelag());
				//String sch = nextFireTime.second() + ' ' + nextFireTime.minute() + ' ' + nextFireTime.hour() + ' ' + nextFireTime.day() + ' ' + nextFireTime.month() + ' ? ' + nextFireTime.year();
				//jobName = getOneTimeJobName(nextFireTime);
				Id jobId = scheduleBQueueJob(nextFireTime);
				jobIds.add(jobId);
			}
		} else {
			throw new LockException();
		}

		return jobIds;
	}

	/*
	 * Start the engine
	 */
	public void stop() {
		if (lock('JobScheduler')) {
			CronTrigger[] ctList = [SELECT Id, CronJobDetail.Id, CronJobDetail.Name, NextFireTime FROM CronTrigger WHERE CronJobDetail.Name LIKE :getJobName() + '%'];
			for (CronTrigger ct : ctList) {
				System.abortJob(ct.Id);
			}
		} else {
			throw new LockException();
		}
	}

	/*
	 *
	 */
	public Id dispatch() {
		Id jobId; 
		if (lock('JobScheduler')) {
			Datetime nextFireTime;
			CronTrigger[] ctList = [SELECT Id, NextFireTime FROM CronTrigger WHERE CronJobDetail.Name LIKE :getJobName() + '%'];
			for (CronTrigger ct : ctList) {
				if (nextFireTime == null || nextFireTime > ct.NextFireTime) {
					nextFireTime = ct.NextFireTime;
				}
			}			

			if (Datetime.now().addSeconds(getSchedulerTimelag()) < nextFireTime) {
				// Not scheduler will be run in next 90 seconds, schedule in 60 seconds
				nextFireTime = Datetime.now().addSeconds(getSchedulerTimelag());

				jobId = scheduleBQueueJob(nextFireTime);		
			}
		}
		return jobId;
	}

	/*
	 * Helper method to acquired a lock
	 */
	public static Boolean lock(String lockName) {
		System.debug(LoggingLevel.FINE, 'Try lock ' + lockName + ' record.');
		try {
			Lock__c[] locks = [SELECT Id FROM Lock__c WHERE Key__c = :lockName FOR UPDATE];
			if (locks.size() == 0) {
				Lock__c lock = new Lock__c(
					Key__c = lockName
					);
				insert lock;
				locks = [SELECT Id FROM Lock__c WHERE Key__c = :lockName FOR UPDATE];
			}

			System.debug(LoggingLevel.FINE, 'Lock ' + lockName + ' is acquired successfully.');
			return true;
		} catch (QueryException ex) {
			// {lockName} is locked
			System.debug(LoggingLevel.ERROR, 'Failed to obtain the ' + lockName + ' lock.');
			return false;
 		} catch (Exception ex) {
 			// General ex
			System.debug(LoggingLevel.ERROR, 'Lock ' + lockName + ' error. ' + ex.getMessage());
 			return false;
 		}
	}



	Integer getPriorityVal(Priority p) {
		if (p == Priority.High) return 2;
		else if (p == Priority.Medium) return 1;
		else return 0;
	}
}