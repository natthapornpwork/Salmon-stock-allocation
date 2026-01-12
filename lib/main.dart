import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/mock/mock_repository.dart';
import 'presentation/blocs/allocation_bloc.dart';
import 'presentation/pages/allocation_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => MockRepository(),
      child: BlocProvider(
        create: (ctx) => AllocationBloc(ctx.read<MockRepository>())
          ..add(const AllocationLoadRequested()),
        child: MaterialApp(
          title: 'Salmon Stock Allocation',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.indigo,
          ),
          home: const AllocationPage(),
        ),
      ),
    );
  }
}
