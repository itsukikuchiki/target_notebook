class DemoGoal {
final String title;
final double progress; // 0..1
final int tasks; // total
final int done; // done
DemoGoal(this.title, {this.progress = .0, this.tasks = 0, this.done = 0});
}


class DemoTask {
final String title;
final DateTime date;
final bool done;
DemoTask(this.title, this.date, {this.done = false});
}


class DemoReflection {
final DateTime date;
final String note;
DemoReflection(this.date, this.note);
}


class DemoData {
static List<DemoGoal> goals() => [
DemoGoal('英语 IELTS 7.5', progress: .42, tasks: 12, done: 5),
DemoGoal('年内读完 12 本书', progress: .58, tasks: 10, done: 6),
DemoGoal('FP2 资格', progress: .33, tasks: 9, done: 3),
];


static List<DemoTask> tasks(DateTime day) {
return [
DemoTask('晨跑 3km', day, done: true),
DemoTask('复习 FP2 章节 5', day),
DemoTask('处理报销单', day),
];
}


static List<DemoReflection> reflections() => [
DemoReflection(DateTime.now(), '今天完成了关键任务，能量不错。'),
DemoReflection(DateTime.now().subtract(const Duration(days: 1)), '需要更早开始专注时段。'),
];
}
