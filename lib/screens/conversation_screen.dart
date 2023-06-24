import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:moli_ai_box/services/palm_api_service.dart';
import 'package:moli_ai_box/utils/icon.dart';
import 'package:provider/provider.dart';
import '../constants/constants.dart';
import '../models/config_model.dart';
import '../models/conversation_model.dart';
import '../models/palm_text_model.dart';
import '../providers/palm_priovider.dart';
import '../repositories/configretion/config_repo.dart';
import '../repositories/conversation/conversation.dart';
import '../widgets/chat_widget.dart';
import '../widgets/form_widget.dart';
import 'conversation_setting_screen.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.conversationData,
  });

  final ConversationModel conversationData;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  bool _isTyping = false;
  List<ConversationMessageModel> messageList = [];
  late final _colorScheme = Theme.of(context).colorScheme;

  late final _backgroundColor = Color.alphaBlend(
      _colorScheme.primary.withOpacity(0.14), _colorScheme.surface);

  late TextEditingController textEditingController;
  late ConversationModel currentConversation;

  @override
  void initState() {
    textEditingController = TextEditingController();
    super.initState();
    _initDefaultConfig();
    _initConversation();
  }

  Future<void> _initConversation() async {
    setState(() {
      currentConversation = widget.conversationData.copy();
    });
    final palmProvider =
        Provider.of<PalmSettingProvider>(context, listen: false);
    if (currentConversation.id == 0) {
      // create new
      // print(palmProvider.getSqliteClient());
      ConversationModel cnv = ConversationModel(
          id: 0,
          title: currentConversation.title,
          prompt: "prompt",
          desc: "desc",
          icon: currentConversation.icon,
          modelName: widget.conversationData.modelName,
          rank: 0,
          lastTime: 0);
      print("cnv $cnv");
      int id = await ConversationReop().createConversation(cnv);
      currentConversation.id = id;
      palmProvider.setCurrentConversationInfo(currentConversation);
    } else {
      ConversationModel? cnv =
          await ConversationReop().getConversationById(currentConversation.id);
      if (cnv != null) {
        palmProvider.setCurrentModel(cnv.modelName);
      }
    }
  }

  void _initDefaultConfig() async {
    final palmProvider =
        Provider.of<PalmSettingProvider>(context, listen: false);
    var configMap = await ConfigReop().getAllConfigsMap();
    ConfigModel? conf = configMap[palmConfigname];

    if (conf != null) {
      final palmConfig = conf.toPalmConfig();
      palmProvider.setBaseURL(palmConfig.basicUrl);
      palmProvider.setApiKey(palmConfig.apiKey);
      palmProvider.setCurrentModel(palmConfig.modelName);
    }
  }

  @override
  void dispose() {
    textEditingController.dispose();
    _isTyping = false;
    super.dispose();
  }

  void _hideKeyboard(BuildContext context) {
    FocusScope.of(context).requestFocus(FocusNode());
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 4,
        automaticallyImplyLeading: false,
        backgroundColor: _colorScheme.primary,
        shadowColor: Colors.white,
        flexibleSpace: SafeArea(
          child: Container(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    Icons.arrow_back,
                    color: _colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(
                  width: 2,
                ),
                CircleAvatar(
                  child: Icon(convertCodeToIconData(currentConversation.icon)),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        currentConversation.title,
                        style: TextStyle(
                            color: _colorScheme.onPrimary, fontSize: 14),
                      ),
                      const SizedBox(
                        height: 6,
                      ),
                      Text(
                        currentConversation.prompt,
                        style: TextStyle(
                            color: _colorScheme.onSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _navigateToConversationScreen();
                  },
                  icon: const Icon(Icons.settings),
                  color: _colorScheme.onSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => _hideKeyboard(context),
        child: Container(
          color: _backgroundColor,
          child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                children: [
                  Flexible(
                    child: ListView.builder(
                      itemCount: messageList.length,
                      itemBuilder: (context, index) {
                        return ConversationMessageWidget(
                            conversation: messageList[index]);
                      },
                    ),
                  ),
                  if (_isTyping) ...[
                    const SpinKitThreeBounce(
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                  const SizedBox(height: 15),
                  // ChatInputFormWidget(),
                  PromptMessageInputFormWidget(
                      textController: textEditingController,
                      onPressed: () {
                        if (_isTyping) {
                          log("asking");
                        } else {
                          _hideKeyboard(context);
                          sendMessageFCT(context);
                        }
                      }),
                ],
              )),
        ),
      ),
    );
  }

  void _navigateToConversationScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ConversationSettingScreen(conversationData: currentConversation),
      ),
    );
  }

  Future<void> sendMessageFCT(BuildContext context) async {
    try {
      String text = textEditingController.text;
      setState(() {
        messageList.add(ConversationMessageModel(msg: text, chatIndex: 0));
        _isTyping = true;
        textEditingController.clear();
      });
      final list = await PalmApiService.getTextReponse(context, text);
      setState(() {
        messageList.add(list[0]);
      });
    } catch (error) {
      log("error $error");
    } finally {
      setState(() {
        _isTyping = false;
      });
    }
  }
}