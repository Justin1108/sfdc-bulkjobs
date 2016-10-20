@isTest
private class JobEngineTest {
	@isTest 
	static void test_AddJob() {
		JobEngine engine = new JobEngine();

		// Positive test
		engine.addJob(JobEngine.Priority.High, 'JobEngine.DummyJobProcessor', new List<String> { '1', '2', '3' });
		Job_Queue__c job = [SELECT Priority__c, Processor__c, Request__c, Status__c FROM Job_Queue__c LIMIT 1];
		System.assertEquals(2, job.Priority__c);
		System.assertEquals('JobEngine.DummyJobProcessor', job.Processor__c);
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
		System.assertEquals(JobEngine.Job_Name, ctList[1].CronJobDetail.Name);
		System.assertEquals(nextRunTime, ctList[1].NextFireTime);
		System.assertEquals(JobEngine.Job_Name + ' - ' + ctList[0].NextFireTime.formatLong(), ctList[0].CronJobDetail.Name);

		engine.stop();
		ctList = [SELECT CronExpression, TimesTriggered, NextFireTime, CronJobDetail.Name FROM CronTrigger WHERE Id IN :jobIds ORDER BY NextFireTime];
		System.assertEquals(0, ctList.size());		
	}
	
}