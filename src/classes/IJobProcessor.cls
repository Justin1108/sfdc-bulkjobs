public interface IJobProcessor {
	Integer getBatchSize();
	void start(String para1, String para2);
	Integer[] execute(String[] requestIds);
}