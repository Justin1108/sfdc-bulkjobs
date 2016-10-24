@isTest
private class JobEngineTest {
	/* 
	 * Used for test class only
	 */
	public class DummyJobProcessor implements IJobProcessor {
		public void start(String para1, String para2) {}
		public Integer getBatchSize() { return 1; }
		public Integer[] execute(String[] requestIds) {
			return new List<Integer> { 1 };
		}
	}

	@isTest 
	static void test_AddJob() {
		JobEngine engine = new JobEngine();

		// Positive test
		engine.addJob(JobEngine.Priority.High, 'JobEngineTest.DummyJobProcessor', new List<String> { '1', '2', '3' });
		Job_Queue__c job = [SELECT Priority__c, Processor__c, Request__c, Status__c FROM Job_Queue__c LIMIT 1];
		System.assertEquals(2, job.Priority__c);
		System.assertEquals('JobEngineTest.DummyJobProcessor', job.Processor__c);
		System.assertEquals('Ready', job.Status__c);
		System.assertEquals('1,2,3', job.Request__c);

		// Negative test 1
		try {
			engine.addJob(JobEngine.Priority.Medium, 'JobEngine1', new List<String>());
			System.assert(false, 'Class does not exist exception is not captured.');
		} catch (JobEngine.AppException ex) {
			System.debug(ex.getMessage());
		}

		// Negative test 1
		try {
			engine.addJob(JobEngine.Priority.Medium, 'JobEngine', new List<String>());
			System.assert(false, 'Class does not exist exception is not captured.');
		} catch (JobEngine.AppException ex) {
			System.debug(ex.getMessage());
		}
	}

	@isTest
	static void test_StartStop() {
		// Scenario #1
		Datetime nextRunTime = Datetime.now().addHours(1); // One hour later 
		String cronExp = String.format('{0} {1} {2} * * ? *', new List<String> { 
			String.valueOf(nextRunTime.second()), 
			String.valueOf(nextRunTime.minute()), 
			String.valueOf(nextRunTime.hour())
			});

		JobEngine engine = new JobEngine();
		List<Id> jobIds = engine.start(cronExp);
		System.assertEquals(2, jobIds.size());

		// Verify the CronTrigger Object
		CronTrigger[] ctList = [SELECT CronExpression, TimesTriggered, NextFireTime, CronJobDetail.Name FROM CronTrigger WHERE Id IN :jobIds ORDER BY NextFireTime];
		System.debug(JSON.serialize(ctList));

		// Two should be created, one is one time, the other is repeat
		System.assertEquals(2, ctList.size());
		System.assertEquals(JobEngine.getRepeatJobName(), ctList[1].CronJobDetail.Name);
		System.assertEquals(nextRunTime, ctList[1].NextFireTime);
		System.assertEquals(JobEngine.getOneTimeJobName(ctList[0].NextFireTime), ctList[0].CronJobDetail.Name);

		engine.stop();
		ctList = [SELECT CronExpression, TimesTriggered, NextFireTime, CronJobDetail.Name FROM CronTrigger WHERE Id IN :jobIds ORDER BY NextFireTime];
		System.assertEquals(0, ctList.size());		

		// Scenario #2
		nextRunTime = Datetime.now().addSeconds(4); // 4 seconds later 
		cronExp = String.format('{0} {1} {2} * * ? *', new List<String> { 
			String.valueOf(nextRunTime.second()), 
			String.valueOf(nextRunTime.minute()), 
			String.valueOf(nextRunTime.hour())
			});
		jobIds = engine.start(cronExp);
		// The next fire time for the scheduler is within 5 minutes, no one time scheduler is created.
		System.assertEquals(1, jobIds.size()); 
		engine.stop();
	}

	@isTest
	static void test_Dispatch() {
		JobEngine engine = new JobEngine();
		System.assertEquals(null, engine.dispatch());

		System.assert(engine.start().size() > 0);
		engine.stop();
		System.assertEquals(null, engine.dispatch());

		Test.startTest();
		List<Id> jobIds = engine.start();
		System.debug('jobIds: ' + jobIds);
		Test.stopTest();
		CronTrigger[] ctList = [SELECT CronExpression, TimesTriggered, NextFireTime, CronJobDetail.Name FROM CronTrigger WHERE Id IN :jobIds ORDER BY NextFireTime];
		System.debug('ctList: ' + JSON.serialize(ctList));

		System.assertEquals(1, ctList.size());
		
		String jobId = engine.dispatch();
		System.debug(jobId);
		System.assertNotEquals(null, jobId);



	}

	@isTest
	static void test_Scheduler1() {
		JobEngine engine = new JobEngine();

		Test.startTest();
		List<Id> schIds = engine.start();
		System.assert(schIds.size() >= 1);
		Test.stopTest();

		System.debug('schIds: ' + schIds);
		if (schIds.size() > 1) {
			CronTrigger[] ctList = [SELECT Id FROM CronTrigger WHERE Id IN :schIds];
			System.assertEquals(1, ctList.size());
			System.debug('One time job is terminated by itself.');
		}

	}

	@isTest
	static void test_Scheduler2() {
		JobEngine engine = new JobEngine();

		//
		Test.startTest();
		engine.addJob(JobEngine.Priority.High, 'JobEngineTest.DummyJobProcessor', new List<String> { '3' });
		System.assertEquals('Ready', [SELECT Status__c FROM Job_Queue__c LIMIT 1].Status__c);
		engine.start();
		Test.stopTest();
		System.debug('AsyncApexJob: ' + JSON.serialize([SELECT JobType, MethodName, Status FROM AsyncApexJob WHERE JobType='Queueable']));
		System.assertEquals('Running', [SELECT Status__c FROM Job_Queue__c LIMIT 1].Status__c);

	}

	@isTest
	static void test_JobProcessor() {
		JobEngine engine = new JobEngine();

		engine.addJob(JobEngine.Priority.Low, 'JobEngineTest.DummyJobProcessor', new List<String> { '1' });
		engine.addJob(JobEngine.Priority.Medium, 'JobEngineTest.DummyJobProcessor', new List<String> { '2' });
		engine.addJob(JobEngine.Priority.High, 'JobEngineTest.DummyJobProcessor', new List<String> { '3' });

		Test.startTest();
		JobScheduler js = new JobScheduler();
		js.execute(null);
		Test.stopTest();

		System.debug('AsyncApexJob: ' + JSON.serialize([SELECT JobType, MethodName, Status FROM AsyncApexJob WHERE JobType='Queueable']));
		Job_Queue__c[] jobs = [SELECT Priority__c, Processor__c, Request__c, Response__c, Status__c FROM Job_Queue__c];
		System.debug('jobs: ' + JSON.serialize(jobs));
	}
	
}